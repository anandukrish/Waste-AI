# Security policy

WASTE is an early preview. Please do not publish pairing tokens, API keys,
private logs, certificates or personal conversation history in issues.

For a security report, contact the repository maintainer privately before
opening a public issue. Include a minimal reproduction without secrets.

The development companion binds to loopback by default. Do not expose it to
the public internet or use port forwarding. Non-loopback mode requires
explicit HTTPS certificates and a concrete IP address.
