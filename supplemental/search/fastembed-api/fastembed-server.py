from fastembed import TextEmbedding
from fastapi import FastAPI
from pydantic import BaseModel

models = {}

app = FastAPI()

class EmbeddingRequest(BaseModel):
    model: str
    input: str

@app.post("/v1/embeddings")
def embeddings(request: EmbeddingRequest):
    model = models.get(request.model) or TextEmbedding(request.model)
    models[request.model] = model
    embeddings = next(model.embed(request.input)).tolist()
    return {"data": [{"embedding": embeddings}]}

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=11345)
