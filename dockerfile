#FROM ubuntu:18.04
FROM alpine:3.7

# Config
ENV app_dir='./app'
WORKDIR ${app_dir}

# Install dependencies
RUN apk add --no-cache python3
RUN pip3 install --upgrade pip

# Copy app files
RUN mkdir -p /app
COPY ./ /app

# Install Python requirements
RUN python3 -m pip install --upgrade pip
RUN pip3 install -r ${app_dir}/requirements.txt

EXPOSE 80/tcp

CMD cd ${app_dir} && python3 hello.py
