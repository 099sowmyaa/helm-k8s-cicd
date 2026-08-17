FROM ubuntu:22.04
RUN apt update && apt install python3 -y && apt install python3-flask -y && apt install python3-redis -y
COPY app.py /tmp
EXPOSE 8080
CMD ["python3", "/tmp/app.py"]

