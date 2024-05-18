from fastembed import TextEmbedding
from fastapi import FastAPI
from pydantic import BaseModel

model = TextEmbedding("snowflake/snowflake-arctic-embed-xs")

app = FastAPI()

class EmbeddingRequest(BaseModel):
    model: str
    prompt: str

@app.post("/api/embeddings")
def embeddings(request: EmbeddingRequest):
    embeddings = next(model.embed(request.prompt)).tolist()
    return {"embedding": embeddings}

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=11345)
