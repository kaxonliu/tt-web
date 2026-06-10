from flask import Flask, jsonify

app = Flask(__name__)


@app.route('/', methods=['GET'])
def hello():
    """返回 Hello World JSON 响应"""
    print("Received a request to '/' endpoint")
    print("Received a request to '/' endpoint")
    return jsonify({"message": "Hello World"})


if __name__ == '__main__':
    # 本地直接运行时使用 Flask 开发服务器（非生产环境）
    app.run(host='0.0.0.0', port=5000)