{ pkgs, lib }:

pkgs.writers.writePython3Bin "pylontech2mqtt" {
  libraries = with pkgs.python3Packages; [ pyserial paho-mqtt ];
  flakeIgnore = [ "E501" ];
} ''
  import argparse
  import json
  import sys
  import time

  import paho.mqtt.client as mqtt
  import serial

  CID1 = 0x46
  CID2_GET_VALUES = 0x42
  CID2_GET_SYSTEM_ALARM = 0x62
  # Single-group installs answer system-level commands (0x60-0x64) on the
  # master's own module address, not a distinct "system" address - see
  # PYLON low voltage Protocol RS485 s2 ("...请确保主机为 X000...").
  SYSTEM_ALARM_ADDR = 0x02

  # PYLON low voltage Protocol RS485 s2.3 "获取电池组系统状态告警量信息"
  ALARM_STATUS_1_BITS = [
      (7, "module_voltage_high"),
      (6, "module_voltage_low"),
      (5, "cell_voltage_high"),
      (4, "cell_voltage_low"),
      (3, "cell_temp_high"),
      (2, "cell_temp_low"),
      (1, "mosfet_high_temp"),
      (0, "cell_voltage_inconsistent"),
  ]
  ALARM_STATUS_2_BITS = [
      (7, "cell_temp_inconsistent"),
      (6, "charge_overcurrent"),
      (5, "discharge_overcurrent"),
      (4, "internal_communication_error"),
  ]
  PROTECT_STATUS_1_BITS = [
      (7, "module_voltage_overvoltage"),
      (6, "module_voltage_undervoltage"),
      (5, "cell_voltage_overvoltage"),
      (4, "cell_voltage_undervoltage"),
      (3, "cell_temp_overtemp"),
      (2, "cell_temp_undertemp"),
      (1, "mosfet_overtemp"),
  ]
  PROTECT_STATUS_2_BITS = [
      (6, "charge_overcurrent_protect"),
      (5, "discharge_overcurrent_protect"),
      (3, "system_fault_protect"),
  ]


  def get_info_length(info: bytes) -> int:
      lenid = len(info)
      if lenid == 0:
          return 0
      lenid_sum = (lenid & 0xF) + ((lenid >> 4) & 0xF) + ((lenid >> 8) & 0xF)
      lenid_modulo = lenid_sum % 16
      lenid_invert_plus_one = 0b1111 - lenid_modulo + 1
      return (lenid_invert_plus_one << 12) + lenid


  def get_frame_checksum(frame: bytes) -> int:
      s = sum(frame)
      s = ~s
      s %= 0x10000
      s += 1
      return s


  def encode_cmd(address: int, cid2: int, info: bytes = b"") -> bytes:
      info_length = get_info_length(info)
      frame = "{:02X}{:02X}{:02X}{:02X}{:04X}".format(0x20, address, CID1, cid2, info_length).encode()
      frame += info
      chksum = get_frame_checksum(frame)
      return b"~" + frame + "{:04X}".format(chksum).encode() + b"\r"


  def decode_frame(resp: bytes) -> bytes:
      s = resp.decode()
      if not (s.startswith("~") and s.endswith("\r")):
          raise ValueError(f"malformed frame: {resp!r}")
      s = s[1:-1]
      rtn = s[6:8]
      if rtn != "00":
          raise ValueError(f"battery returned error code {rtn}: {resp!r}")
      info_hex = s[12:-4]
      return bytes.fromhex(info_hex)


  def parse_values(info: bytes) -> dict:
      i = 1  # skip INFOFLAG
      i += 1  # NumberOfModule
      num_cells = info[i]
      i += 1
      cell_v = []
      for _ in range(num_cells):
          v = int.from_bytes(info[i:i + 2], "big", signed=True)
          i += 2
          cell_v.append(v / 1000)
      num_temp = info[i]
      i += 1
      i += 2  # AverageBMSTemperature, not used below
      cell_temps = []
      for _ in range(num_temp - 1):
          t = int.from_bytes(info[i:i + 2], "big", signed=True)
          i += 2
          cell_temps.append((t - 2731) / 10)
      current = int.from_bytes(info[i:i + 2], "big", signed=True) / 10
      i += 2
      voltage = int.from_bytes(info[i:i + 2], "big", signed=False) / 1000
      i += 2
      remaining1 = int.from_bytes(info[i:i + 2], "big", signed=False) / 1000
      i += 2
      user_items = info[i]
      i += 1
      total1 = int.from_bytes(info[i:i + 2], "big", signed=False) / 1000
      i += 2
      cycle = int.from_bytes(info[i:i + 2], "big", signed=False)
      i += 2
      remaining, total = remaining1, total1
      if user_items > 2:
          remaining = int.from_bytes(info[i:i + 3], "big", signed=False) / 1000
          i += 3
          total = int.from_bytes(info[i:i + 3], "big", signed=False) / 1000
          i += 3

      return {
          "voltage": round(voltage, 3),
          "current": round(current, 1),
          "soc_pct": round(100 * remaining / total, 1) if total else None,
          "remaining_ah": round(remaining, 2),
          "total_ah": round(total, 2),
          "cycle": cycle,
          "cell_min_v": round(min(cell_v), 3),
          "cell_max_v": round(max(cell_v), 3),
          "cell_imbalance_mv": round((max(cell_v) - min(cell_v)) * 1000, 1),
          "cell_voltages": cell_v,
          "avg_temp": round(sum(cell_temps) / len(cell_temps), 1) if cell_temps else None,
          "min_temp": round(min(cell_temps), 1) if cell_temps else None,
          "max_temp": round(max(cell_temps), 1) if cell_temps else None,
      }


  def query_pack(ser: serial.Serial, address: int) -> dict:
      info = "{:02X}".format(address).encode()
      ser.reset_input_buffer()
      ser.write(encode_cmd(address, CID2_GET_VALUES, info))
      resp = ser.read(4096)
      if not resp:
          raise TimeoutError(f"no response from pack at address {address}")
      return parse_values(decode_frame(resp))


  def decode_bits(byte: int, bits: list) -> dict:
      return {name: bool(byte & (1 << bit)) for bit, name in bits}


  def query_system_alarm(ser: serial.Serial) -> dict:
      ser.reset_input_buffer()
      ser.write(encode_cmd(SYSTEM_ALARM_ADDR, CID2_GET_SYSTEM_ALARM, b""))
      resp = ser.read(4096)
      if not resp:
          raise TimeoutError("no response to system alarm query")
      info = decode_frame(resp)
      alarm1, alarm2, protect1, protect2 = info[0], info[1], info[2], info[3]

      flags = {}
      flags.update(decode_bits(alarm1, ALARM_STATUS_1_BITS))
      flags.update(decode_bits(alarm2, ALARM_STATUS_2_BITS))
      flags.update(decode_bits(protect1, PROTECT_STATUS_1_BITS))
      flags.update(decode_bits(protect2, PROTECT_STATUS_2_BITS))
      active = sorted(name for name, on in flags.items() if on)

      return {
          "problem": bool(active),
          "active_alarms": active,
          "alarm_status_1": alarm1,
          "alarm_status_2": alarm2,
          "protection_status_1": protect1,
          "protection_status_2": protect2,
          **flags,
      }


  def main():
      p = argparse.ArgumentParser()
      p.add_argument("--port", required=True)
      p.add_argument("--baud", type=int, default=115200)
      p.add_argument("--addresses", required=True, help="comma-separated Pylontech addresses, e.g. 2,3")
      p.add_argument("--mqtt-host", default="localhost")
      p.add_argument("--mqtt-port", type=int, default=1883)
      p.add_argument("--mqtt-user", required=True)
      p.add_argument("--mqtt-password", required=True)
      p.add_argument("--mqtt-topic-prefix", default="pylontech/")
      args = p.parse_args()

      addresses = [int(a) for a in args.addresses.split(",")]

      client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
      client.username_pw_set(args.mqtt_user, args.mqtt_password)
      client.connect(args.mqtt_host, args.mqtt_port)

      ser = serial.Serial(args.port, args.baud, timeout=1.5)
      time.sleep(0.3)

      failures = 0
      for address in addresses:
          try:
              values = query_pack(ser, address)
          except Exception as e:
              print(f"pack {address}: {e}", file=sys.stderr)
              failures += 1
              continue
          topic = f"{args.mqtt_topic_prefix}pack_{address}/state"
          client.publish(topic, json.dumps(values), retain=True)
          print(f"pack {address}: {values}")

      try:
          alarm = query_system_alarm(ser)
      except Exception as e:
          print(f"system alarm: {e}", file=sys.stderr)
          failures += 1
      else:
          topic = f"{args.mqtt_topic_prefix}system/alarm"
          client.publish(topic, json.dumps(alarm), retain=True)
          print(f"system alarm: {alarm}")

      ser.close()
      client.disconnect()

      if failures == len(addresses) + 1:
          sys.exit(1)


  if __name__ == "__main__":
      main()
''
