# SPARQL KGQA webapp

Web application for SPARQL generation backends.
Supports the following tasks:
- SPARQL generation

## Build

Configure your website using [lib/config.dart](lib/config.dart).
After that build it using `flutter build web --release`, or
if you do not have flutter installed use `docker build -t <image-name> .` which
creates a nginx docker image hosting the website. Run it using
`docker run -p <port>:80 <image-name>`.

## Endpoints

Endpoints required for all question answering backends:
- [GET] /models
```
  returns:
    {
      "task": "SPARQL generation", 
      "models": [
        {
          "name": "best_model_v1", 
          "description": "this model is so good", 
          "tags": ["arch::transformer", "speed::fast", "lang::en", ...]
        }, 
        ...
      ]
    }
```
- [GET] /info
```
  returns:
    {
      "gpu": ["GTX 1080Ti", "RTX 2080Ti", ...],
      "cpu": "Intel i7 9700K",
      "timeout": 10.0
    }
```

Also all endpoints should support arbitrary leading base URLs,
e.g. /api/v1/llm/info

In particular, for this webapp, the tasks should be run with the
following base URLs:
- SPARQL generation: /api

Endpoints required for SPARQL generation:
- [Websocket] /generate
```
  requires:
    {
      "model": "best_model_v1", 
      "text": "who is albert einstein?"
    }
  optional:
    {
      "info": "some additional guidance",
      "sampling_strategy": "greedy",
      "beam_width": 5,
      "top_k": 10,
      "top_p": 0.95,
      "temperature": 1.0,
    }
  returns stream of:
    {
      "output": "SELECT ...",
      "runtime": {"s": 10, "b": 20}
    } 
```