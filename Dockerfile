# Dockerfile
FROM node:20-alpine

WORKDIR /app

# App code
COPY index.html admin.html server.js ./

# ✅ Include packs inside the image
#    If you don't have a /packs folder locally yet, create one.
COPY packs ./packs

ENV PORT=8787
EXPOSE 8787

CMD ["node", "server.js"]