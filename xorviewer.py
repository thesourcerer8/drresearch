from flask import Flask
from flask import request
import subprocess
import os
app = Flask(__name__)

@app.route("/")
def hello():
    os.environ["GATEWAY_INTERFACE"]="CGI/1.1"
    os.environ["SERVER_NAME"]="localhost"
    os.environ["REQUEST_METHOD"]="GET"
    os.environ["SCRIPT_NAME"]="./xorviewer.pl"
    os.environ["QUERY_STRING"]=request.query_string.decode('utf-8')
    output=subprocess.check_output("./xorviewer.pl", shell=True).decode('utf-8')
    mylist=output.split('\n\n',1)
    return mylist[1].encode();

if __name__ == "__main__":
    app.run()
