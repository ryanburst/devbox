# Windows scripts (devbox)

PowerShell and batch files in this folder must be **ASCII only** (no Unicode arrows, em dashes, or smart quotes). Corporate PowerShell 5.1 often fails to parse UTF-8 special characters.

Use `-` not em dash, `->` not arrow. Avoid double-quote inside single-quoted strings.
Do not use angle brackets in strings (use your-hostname.local:port not less-than name greater-than).
