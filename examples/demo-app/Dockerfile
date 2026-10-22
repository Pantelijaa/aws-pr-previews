FROM node:24-slim
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.0.1 /lambda-adapter /opt/extensions/lambda-adapter
WORKDIR /app
COPY server.ts .
USER node
EXPOSE 8080
CMD ["node", "server.ts"]