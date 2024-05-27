# How to enable text search for Chinese, Japanese and Korean

Pleroma's full text search feature is powered by PostgreSQL's native [text search](https://www.postgresql.org/docs/current/textsearch.html), it works well out of box for most of languages, but needs extra configurations for some asian languages like Chinese, Japanese and Korean (CJK).


## Setup and test the new search config

In most cases, you would need an extension installed to support parsing CJK text. Here are a few extensions you may choose from, or you are more than welcome to share additional ones you found working for you with the rest of Pleroma community.

 * [a generic n-gram parser](https://github.com/huangjimmy/pg_cjk_parser) supports Simplifed/Traditional Chinese, Japanese, and Korean
 * [a Korean parser](https://github.com/i0seph/textsearch_ko) based on mecab
 * [a Japanese parser](https://www.amris.co.jp/tsja/index.html) based on mecab
 * [zhparser](https://github.com/amutu/zhparser/) is a PostgreSQL extension base on the Simple Chinese Word Segmentation(SCWS)
 * [another Chinese parser](https://github.com/jaiminpan/pg_jieba) based on Jieba Chinese Word Segmentation
 
Once you have the new search config , make sure you test it with the `pleroma` user in PostgreSQL (change `YOUR.CONFIG` to your real configuration name)
```
SELECT ts_debug('YOUR.CONFIG', '安装和配置Nginx, ElixirとErlangをインストールします');
```
Check output of the query, and see if it matches your expectation.


## Update text search config and index in database

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database set_text_search_config YOUR.CONFIG
    ```

=== "From Source"

    ```sh
    mix pleroma.database set_text_search_config YOUR.CONFIG
    ```

Note: index update may take a while, and it can be done while the instance is up and running, so you may restart db connection as soon as you see `Recreate index` in task output.

## Restart database connection
Since some changes above will only apply with a new database connection, you will have to restart either Pleroma or PostgreSQL process, or use `pg_terminate_backend` SQL command without restarting either. 

Now the search results of statuses should be much more friendly for your language of choice, the results for searching users and tags were not changed, as the default parsing/matching should work for most cases. 
