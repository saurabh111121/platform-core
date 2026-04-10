FROM node:20-alpine
WORKDIR /app
RUN echo '{"name":"app","version":"1.0.0","scripts":{"start":"node server.js"}}' > package.json
RUN echo 'require("http").createServer((req,res)=>{res.writeHead(200);res.end("ok")}).listen(8080)' > server.js
EXPOSE 8080
USER node
CMD ["node", "server.js"]
