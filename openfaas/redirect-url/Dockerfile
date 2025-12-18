FROM ghcr.io/openfaas/of-watchdog:0.9.11 as watchdog

FROM python:3.9-slim

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt flask

# Copy watchdog
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

# Copy function
WORKDIR /home/app
COPY handler.py .
COPY server.py .

# Configure watchdog for HTTP mode
ENV fprocess="python3 /home/app/server.py"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:5000"
ENV write_timeout="60s"
ENV read_timeout="60s"

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
