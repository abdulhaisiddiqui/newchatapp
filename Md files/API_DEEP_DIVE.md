# API Development Research — Dart, Python, JavaScript, Go

## 📌 What is an API?

An **API (Application Programming Interface)** allows different software systems to communicate — e.g., a mobile app talking to a backend server.
APIs typically expose **HTTP endpoints** that respond with JSON — e.g., `GET /users`, `POST /login`.

## 🧠 Core Concepts (Across Languages)

| Concept      | Meaning                                                         |
| ------------ | --------------------------------------------------------------- |
| HTTP Methods | GET, POST, PUT, DELETE                                          |
| REST         | Representational State Transfer — standard conventions for APIs |
| JSON         | Common data format exchanges                                    |
| Middleware   | Code that runs between request & response                       |
| Routing      | Mapping URL + method → handler                                  |
| Framework    | Tools that simplify web/API server creation                     |
| Deployment   | Hosting your API server (e.g., cloud/VPS)                       |

---

## 🟦 Dart API Development

Dart can run backend servers (not just Flutter clients). The main ecosystem tools:

### 🛠️ Libraries & Frameworks

* **`shelf`** — lightweight HTTP server middleware for Dart. ([Dart packages][1])
* **`shelf_router`** — add routing on top of `shelf`. ([DEV Community][2])
* **Serverpod / Dart Frog** — more advanced frameworks (optional beyond shelf). ([Medium][3])

### 📦 Shelf Server — Basic Example

```dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// Create router
final app = Router()
  ..get('/hello', (Request req) => Response.ok(jsonEncode({'message': 'Hello Dart API!'}), headers: {'Content-Type':'application/json'}))
  ..post('/echo', (Request req) async {
    final body = await req.readAsString();
    return Response.ok(jsonEncode({'echo': body}), headers: {'Content-Type':'application/json'});
  });

void main() async {
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(app);
  await io.serve(handler, 'localhost', 8080);
  print('Server running at http://localhost:8080');
}
```

* This sets up a server and routes using `shelf_router`. ([Dart packages][1])

### 📌 Notes

✔ You can do CRUD with GET, POST, PUT, DELETE using route definitions. ([DEV Community][2])
✔ For production, add CORS, authentication, database, etc.

---

## 🐍 Python API Development

Python has multiple web frameworks for APIs. The most common:

### 🧰 Frameworks

* **FastAPI** — modern, fast, async, automatic docs (Swagger/OpenAPI). ([Wikipedia][4])
* **Flask** — minimal, easy. ([roborabbit.com][5])
* **Django + DRF** — full-featured. ([Medium][6])

### 🚀 FastAPI Example

```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class Item(BaseModel):
    name: str
    price: float

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI"}

@app.post("/items/")
def create_item(item: Item):
    return {"item_name": item.name, "item_price": item.price}
```

Run:

```
uvicorn main:app --reload
```

* Auto docs: [http://localhost:8000/docs](http://localhost:8000/docs). ([Wikipedia][4])

### 🐣 Flask Example

```python
from flask import Flask, request

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello Flask API"

@app.route('/echo', methods=['POST'])
def echo():
    data = request.get_json()
    return {"received": data}

if __name__ == '__main__':
    app.run(debug=True)
```

* Simpler but less automatic docs than FastAPI. ([roborabbit.com][5])

---

## 🟨 JavaScript API Development

Node.js is one of the most popular ways to create APIs in JS.

### 🛠️ Tools

* **Express.js** — minimal, widely used. ([backendbaz.com][7])
* **NestJS** — structured & scalable (optional advanced). ([Medium][6])

### 🧪 Express Basic Example

```js
const express = require('express');
const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: "Hello Express API" });
});

app.post('/echo', (req, res) => {
  res.json({ echo: req.body });
});

app.listen(3000, () => console.log('Server running on http://localhost:3000'));
```

* Lightweight & easy. ([backendbaz.com][7])

👉 Remember CORS/security middleware like `cors` in real projects.

---

## 🟩 Go API Development

Go’s speed and concurrency make it excellent for APIs.

### 🛠️ Tools

* **Gin** — popular HTTP framework for routing, middleware, JSON. ([Go][8])
* **net/http** — standard library (manual routing).

### 🎯 Gin Example

```go
package main

import (
  "github.com/gin-gonic/gin"
)

func main() {
  r := gin.Default()

  r.GET("/ping", func(c *gin.Context) {
    c.JSON(200, gin.H{"message": "pong"})
  })

  r.POST("/echo", func(c *gin.Context) {
    var body map[string]interface{}
    c.BindJSON(&body)
    c.JSON(200, gin.H{"echo": body})
  })

  r.Run() // defaults to :8080
}
```

* Simple endpoints with JSON binding. ([Go][8])

---

## 🚀 Deployment & Next Steps

Once you have your API running locally, common next steps include:

✔ **Add authentication** (JWT / OAuth)
✔ **Database integration** (PostgreSQL, MongoDB, SQLite)
✔ **API docs** (OpenAPI/Swagger)
✔ **Rate limiting / caching**
✔ **Dockerization & CI/CD**
✔ **Cloud deployment** (Cloud Run, AWS, Azure, VPS)

---

## 💾 Databases

### 🐍 Python (FastAPI with SQLAlchemy)

```python
from fastapi import FastAPI, Depends
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

DATABASE_URL = "postgresql://user:password@localhost/dbname"

Base = declarative_base()

class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String, index=True)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/items/{item_id}")
def read_item(item_id: int, db: Session = Depends(get_db)):
    return db.query(Item).filter(Item.id == item_id).first()
```

### 🟨 JavaScript (Express with Sequelize)

```javascript
const { Sequelize, DataTypes } = require('sequelize');
const sequelize = new Sequelize('postgres://user:password@localhost:5432/dbname');

const Item = sequelize.define('Item', {
  name: DataTypes.STRING,
  description: DataTypes.STRING,
});

app.get('/items/:id', async (req, res) => {
  const item = await Item.findByPk(req.params.id);
  res.json(item);
});
```

### 🟩 Go (with pgx)

```go
package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v4"
)

func main() {
	conn, err := pgx.Connect(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())

	var name string
	var description string
	err = conn.QueryRow(context.Background(), "select name, description from items where id=$1", 1).Scan(&name, &description)
	if err != nil {
		fmt.Fprintf(os.Stderr, "QueryRow failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(name, description)
}
```

### 🟦 Dart (with postgres)

```dart
import 'package:postgres/postgres.dart';

void main() async {
  final conn = PostgreSQLConnection("localhost", 5432, "dbname", username: "user", password: "password");
  await conn.open();

  List<List<dynamic>> results = await conn.query("SELECT name, description FROM items WHERE id = @id", substitutionValues: {
    "id": 1
  });

  for (final row in results) {
    print(row[0]);
    print(row[1]);
  }

  await conn.close();
}
```

---

## 🔐 Authentication (JWT)

### 🐍 Python (FastAPI)

```python
from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import OAuth2PasswordBearer
import jwt

SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
        return username
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

@app.get("/users/me")
async def read_users_me(current_user: str = Depends(get_current_user)):
    return {"username": current_user}
```

### 🟨 JavaScript (Express)

```javascript
const jwt = require('jsonwebtoken');

function auth(req, res, next) {
  const token = req.header('x-auth-token');
  if (!token) return res.status(401).send('Access denied. No token provided.');

  try {
    const decoded = jwt.verify(token, 'your-secret-key');
    req.user = decoded;
    next();
  } catch (ex) {
    res.status(400).send('Invalid token.');
  }
}

app.get('/api/me', auth, (req, res) => {
  res.send(req.user);
});
```

### 🟩 Go (Gin)

```go
func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := c.GetHeader("Authorization")
		if tokenString == "" {
			c.JSON(401, gin.H{"error": "request does not contain an access token"})
			c.Abort()
			return
		}
		// Validate token
		c.Next()
	}
}

r.GET("/protected", authMiddleware(), func(c *gin.Context) {
    c.JSON(200, gin.H{"message": "hello world"})
})
```

### 🟦 Dart (Shelf)

```dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Middleware-based authentication would be implemented here.
```


---

## ⚖️ REST vs GraphQL

### REST

-   **Architecture:** Client-server architecture where clients send requests to servers to retrieve or modify resources.
-   **Endpoints:** Multiple endpoints for different resources (e.g., `/users`, `/posts`).
-   **Data Fetching:** Over-fetching or under-fetching of data is common.
-   **Example:**
    -   `GET /users/1` - get user with id 1
    -   `GET /users/1/posts` - get posts for user with id 1

### GraphQL

-   **Architecture:** A query language for APIs and a runtime for fulfilling those queries with your existing data.
-   **Endpoints:** Single endpoint for all queries.
-   **Data Fetching:** Clients can request exactly the data they need.
-   **Example:**
    ```graphql
    query {
      user(id: 1) {
        name
        posts {
          title
        }
      }
    }
    ```

---

## 🧠 Additional Notes & Best Practices

### 📌 Testing

* Use tools like **Postman / curl** to test endpoints.

### 💡 API Design

* Follow RESTful conventions; use appropriate status codes.
* Provide consistent response formats.

### 📈 Performance

* Python async (FastAPI) is faster than WSGI for concurrency. ([Wikipedia][4])
* Go compiles to a single binary with low overhead. ([Go][8])
* Node’s ecosystem is huge but slightly heavier.

---

## 📚 Sources (for reference & further reading)

* Go Gin tutorial (official) — how to serve REST API with Go & Gin. ([Go][8])
* FastAPI Overview — Python web API framework. ([Wikipedia][4])
* Basic API creation with Express & FastAPI examples. ([backendbaz.com][7])
* Dart `shelf` docs & routing tutorials. ([Dart packages][1])

---

If can expand this into **even deeper sections** (databases, auth, real-world REST vs GraphQL, automated tests, deployment guides, CI/CD examples, etc.).

[1]: https://pub.dev/documentation/shelf/latest/?utm_source=chatgpt.com "shelf - Dart API docs"
[2]: https://dev.to/infiniteoverflow/build-apis-for-various-http-methods-in-dart-n87?utm_source=chatgpt.com "Build APIs for various HTTP Methods in Dart"
[3]: https://suragch.medium.com/dart-shelf-server-tutorial-513ea23485a3?utm_source=chatgpt.com "Dart Shelf server tutorial - Suragch"
[4]: https://en.wikipedia.org/wiki/FastAPI?utm_source=chatgpt.com "FastAPI"
[5]: https://www.roborabbit.com/blog/how-to-create-an-api-in-4-steps-with-code-example/?utm_source=chatgpt.com "How to Create an API in 4 Easy Steps (with Code Example in Python)"
[6]: https://medium.com/%40cchaithanya83/apis-without-tears-a-gentle-intro-to-fastapi-ba3667a10bd3?utm_source=chatgpt.com "APIs Without Tears: A Gentle Intro to FastAPI | by chaithanya k | Medium"
[7]: https://backendbaz.com/how-to-create-an-api-fast/?utm_source=chatgpt.com "How to Create an API Fast?   – BackEndBaz"
[8]: https://go.dev/doc/tutorial/web-service-gin?utm_source=chatgpt.com "Tutorial: Developing a RESTful API with Go and Gin - The Go Programming Language"
