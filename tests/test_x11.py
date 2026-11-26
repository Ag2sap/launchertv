import unittest
from unittest.mock import patch

from backend import x11


class RemoveDecorationsTests(unittest.TestCase):
    @patch("backend.x11._send_ewmh")
    @patch("backend.x11._intern", return_value=0x1234)
    @patch("backend.x11._run")
    def test_requests_motif_and_openbox_undecorated_state(
        self, run, intern, send_ewmh
    ):
        x11.remove_decorations("0xa00007")

        run.assert_called_once_with([
            "xprop", "-id", "0xa00007",
            "-f", "_MOTIF_WM_HINTS", "32c",
            "-set", "_MOTIF_WM_HINTS", "0x2, 0x0, 0x0, 0x0, 0x0",
        ])
        intern.assert_called_once_with(b"_OB_WM_STATE_UNDECORATED")
        send_ewmh.assert_called_once_with(
            0xA00007,
            b"_NET_WM_STATE",
            [1, 0x1234, 0, 1, 0],
        )

    @patch("backend.x11._send_ewmh")
    @patch("backend.x11._intern", return_value=0)
    @patch("backend.x11._run")
    def test_skips_openbox_message_when_display_is_unavailable(
        self, run, intern, send_ewmh
    ):
        x11.remove_decorations(123)

        run.assert_called_once()
        intern.assert_called_once_with(b"_OB_WM_STATE_UNDECORATED")
        send_ewmh.assert_not_called()


if __name__ == "__main__":
    unittest.main()
