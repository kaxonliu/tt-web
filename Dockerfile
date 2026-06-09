# 使用官方 Python 运行时作为基础镜像
FROM 192.168.43.80:30002/pythonwebproject/tt-web:latest

# 设置工作目录
WORKDIR /app

# 复制依赖文件并安装
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制应用代码
COPY app.py .

# 暴露应用运行的端口（Gunicorn 默认 8000）
EXPOSE 8000

# 使用 Gunicorn 启动 Flask 应用
# 绑定到 0.0.0.0:8000，app 是 Flask 实例变量名
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]