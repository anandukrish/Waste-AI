"""Run Waste locally; pairing credentials appear only in the user's console."""
import threading
import webbrowser
from companion.server import create_server


def main():
    try:
        server = create_server()
    except OSError:
        print("Waste could not start. Port 8765 may already be in use.")
        return 1
    print("\nWASTE — local-first assistant")
    print("Open: " + server.allowed_origin)
    print("Pairing token (paste into Waste, not into chat):")
    print(server.app.token)
    print("\nTry /help, /time or /calculate 12 * (3 + 4) in Local mode.")
    print("Press Ctrl+C to stop. No background service is installed.\n", flush=True)
    threading.Timer(1, lambda: webbrowser.open(server.allowed_origin)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
