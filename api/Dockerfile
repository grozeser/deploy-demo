FROM python:3.12-slim
WORKDIR /app
COPY app.py .
RUN useradd -m app && mkdir /data && chown app /data
USER app
CMD ["python", "app.py"]
