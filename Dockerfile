FROM nimlang/nim:1.6.8-alpine-onbuild

CMD apk add sqlite-libs sqlite \
    && sqlite3 /mnt/storeg/production.sqlite "CREATE TABLE IF NOT EXISTS states (context CHAR, key CHAR, value CHAR, guild_id CHAR);" \ 
    && ./vel