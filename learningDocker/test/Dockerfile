FROM debian:bookworm


ENV PORT=8080
ENV HOST=MARI


RUN apt update


WORKDIR /app

COPY todo . 



 
RUN touch index.html

ENTRYPOINT ["bash"]



CMD ["-c", "echo App : $HOST && echo Port: $PORT"]