FROM node:24.18.0-alpine3.23@sha256:595398b0081eacda8e1c4c5b97b76cd1020e4d58a8ebcb4843b9bca1e79e7436

WORKDIR /app

ENV NODE_ENV=production \
    PORT=7860

COPY --chown=node:node space/ /app/

USER node

EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --spider http://127.0.0.1:7860/healthz || exit 1

CMD ["node", "server.js"]
