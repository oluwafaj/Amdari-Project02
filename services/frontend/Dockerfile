# Upgraded from python:3.9-slim to eliminate CRITICAL CVEs (CK-01)
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# CK-02 fix — create and switch to non-root user
RUN addgroup --system app && adduser --system --ingroup app app
USER app

# Healthcheck added
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

EXPOSE 5000
CMD ["python", "app.py"]
