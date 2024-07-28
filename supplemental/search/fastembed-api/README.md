# About
This is a minimal implementation of the [OpenAI Embeddings API](https://platform.openai.com/docs/guides/embeddings/what-are-embeddings) meant to be used with the QdrantSearch backend. 

# Usage

The easiest way to run it is to just use docker compose with `docker compose up`. This starts the server on the default configured port. Different models can be used, for a full list of supported models, check the [fastembed documentation](https://qdrant.github.io/fastembed/examples/Supported_Models/). The first time a model is requested it will be downloaded, which can take a few seconds.
