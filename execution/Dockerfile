FROM python:3.9-slim

WORKDIR /app

# Install ib_insync and other dependencies
RUN pip install --no-cache-dir ib_insync

# Copy application files (if any)
COPY . /app

CMD ["python"]
