FROM ghcr.io/openfaas/of-watchdog:0.9.11 as watchdog

FROM python:3.9-slim

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy watchdog
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

# Copy function
WORKDIR /home/app
COPY handler.py .

# Create a simple wrapper for stdin mode
RUN echo '#!/usr/bin/env python3\nimport sys\nfrom handler import handle\nif __name__ == "__main__":\n    req = sys.stdin.read()\n    result = handle(req)\n    if isinstance(result, tuple):\n        print(result[0])\n    else:\n        print(result)' > /home/app/main.py && chmod +x /home/app/main.py

# Configure watchdog for stdin mode
ENV fprocess="python3 /home/app/main.py"
ENV mode="streaming"
ENV write_timeout="60s"
ENV read_timeout="60s"

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
