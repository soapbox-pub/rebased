FROM python:3.9

WORKDIR /code
COPY fastembed-server.py /workdir/fastembed-server.py
COPY requirements.txt /workdir/requirements.txt

RUN pip install -r /workdir/requirements.txt

CMD ["python", "/workdir/fastembed-server.py"]
