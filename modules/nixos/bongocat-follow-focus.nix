{ pkgs, bongocatPackage, keyboardName }:

pkgs.writeScript "bongocat-follow-focus" ''
  #!${pkgs.python3}/bin/python3
  import json
  import os
  import signal
  import socket
  import subprocess
  import sys
  import time

  BONGOCAT = "${bongocatPackage}/bin/bongocat"
  CONFIG = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "bongocat-follow-focus.conf")
  last_config = None
  last_monitor = None
  child = None

  def hypr_socket(name):
      runtime = os.environ.get("XDG_RUNTIME_DIR")
      sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
      if not runtime or not sig:
          raise RuntimeError("Hyprland runtime variables are missing")
      return os.path.join(runtime, "hypr", sig, name)

  def hypr_json(command):
      with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
          sock.connect(hypr_socket(".socket.sock"))
          sock.sendall(("j/" + command).encode())
          chunks = []
          while True:
              chunk = sock.recv(65536)
              if not chunk:
                  break
              chunks.append(chunk)
      return json.loads(b"".join(chunks).decode() or "null")

  def pick_target():
      window = hypr_json("activewindow") or {}
      monitors = hypr_json("monitors") or []
      if not monitors:
          return "", 0

      center_x = None
      center_y = None
      if window.get("mapped", True) and window.get("at") and window.get("size"):
          center_x = window["at"][0] + window["size"][0] / 2
          center_y = window["at"][1] + window["size"][1] / 2

      monitor = None
      if center_x is not None:
          for mon in monitors:
              if (mon["x"] <= center_x < mon["x"] + mon["width"] and
                      mon["y"] <= center_y < mon["y"] + mon["height"]):
                  monitor = mon
                  break
      if monitor is None:
          monitor = next((mon for mon in monitors if mon.get("focused")), monitors[0])
          center_x = monitor["x"] + monitor["width"] / 2

      x_offset = round(center_x - (monitor["x"] + monitor["width"] / 2))
      return monitor.get("name", ""), x_offset

  def render_config():
      monitor, x_offset = pick_target()
      text = f"""# Auto-generated. Follow the focused Hyprland window.
  cat_x_offset={x_offset}
  cat_y_offset=0
  cat_height=80
  cat_align=center
  mirror_x=0
  mirror_y=0
  enable_antialiasing=1
  overlay_position=top
  overlay_height=60
  overlay_opacity=0
  layer=overlay
  idle_frame=0
  keypress_duration=150
  test_animation_duration=200
  test_animation_interval=0
  fps=60
  enable_hand_mapping=1
  idle_sleep_timeout=0
  enable_scheduled_sleep=0
  sleep_begin=22:00
  sleep_end=06:00
  enable_debug=0
  monitor={monitor}
  keyboard_name=${keyboardName}
  hotplug_scan_interval=30
  """
      return monitor, text

  def stop_child():
      global child
      if child is None:
          return
      # --watch-config forks a worker; stop the whole process group so an
      # output-disconnected worker cannot survive a restart and spin.
      try:
          os.killpg(child.pid, signal.SIGTERM)
          child.wait(timeout=2)
      except ProcessLookupError:
          pass
      except subprocess.TimeoutExpired:
          os.killpg(child.pid, signal.SIGKILL)
          child.wait()
      child = None

  def write_config_and_maybe_restart(force_restart=False):
      global last_config, last_monitor, child
      try:
          monitor, text = render_config()
      except Exception as exc:
          print(f"bongocat-follow-focus: {exc}", file=sys.stderr)
          return
      if text != last_config:
          tmp = CONFIG + ".tmp"
          with open(tmp, "w") as f:
              f.write(text)
          os.replace(tmp, CONFIG)
          last_config = text
      if force_restart or child is None or child.poll() is not None or monitor != last_monitor:
          stop_child()
          if monitor:
              child = subprocess.Popen([BONGOCAT, "--watch-config", "--config", CONFIG], start_new_session=True)
          last_monitor = monitor

  def shutdown(signum, frame):
      stop_child()
      raise SystemExit(0)

  signal.signal(signal.SIGTERM, shutdown)
  signal.signal(signal.SIGINT, shutdown)
  write_config_and_maybe_restart()

  while True:
      try:
          with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
              events.connect(hypr_socket(".socket2.sock"))
              buf = b""
              while True:
                  chunk = events.recv(4096)
                  if not chunk:
                      break
                  buf += chunk
                  while b"\n" in buf:
                      line, buf = buf.split(b"\n", 1)
                      if line.startswith((b"monitoradded>>", b"monitorremoved>>", b"monitoraddedv2>>", b"monitorremovedv2>>")):
                          write_config_and_maybe_restart(force_restart=True)
                      elif line.startswith((b"activewindow>>", b"movewindow>>", b"resizewindow>>", b"focusedmon>>", b"monitorfocused>>", b"workspace>>")):
                          write_config_and_maybe_restart()
      except Exception as exc:
          print(f"bongocat-follow-focus: reconnecting after {exc}", file=sys.stderr)
          time.sleep(1)
          write_config_and_maybe_restart(force_restart=True)
''
