FROM python:3.9

WORKDIR /code
COPY fastembed-server.py /workdir/fastembed-server.py

RUN pip install --no-cache-dir --upgrade fastembed fastapi uvicorn

CMD ["python", "/workdir/fastembed-server.py"]
