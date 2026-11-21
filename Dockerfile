# Dockerfile
FROM node:20-alpine

WORKDIR /app

# App code
COPY index.html admin.html server.js ./
# Kunskapsäventyret — separate app served on ADVENTURE_PORT (8788) from the same server
COPY adventure ./adventure

# ✅ Include packs inside the image
#    If you don't have a /packs folder locally yet, create one.
COPY packs ./packs

ENV PORT=8787
ENV ADVENTURE_PORT=8788
EXPOSE 8787 8788

CMD ["node", "server.js"]