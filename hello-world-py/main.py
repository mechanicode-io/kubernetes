import os
import socket

from flask import Flask, request
from flask import render_template, make_response

import config

app = Flask(__name__)


@app.route('/favicon.ico')
def favicon():
    return make_response({}, 200)


@app.route('/healthz')
def healthz():
    print('Healthy!')
    return make_response({}, 200)


@app.route("/")
def hello_world():
    hostname = socket.gethostname()
    return render_template('index.j2.html',
                           hostname=hostname,
                           headers=request.headers,
                           app_ip=os.environ.get('HELLO_WORLD_PORT', None),
                           svc_ip=os.environ.get('KUBERNETES_PORT', None),
                           )


@app.route("/<string:path>")
def catch_all(path):
    print('Failed health check! Update to path /healthz')
    return make_response({'msg': f'unknown path'}, 500)


if __name__ == '__main__':
    print(f'Ready to receive requests on {config.PORT}')
    app.run(host='0.0.0.0', port=config.PORT, threaded=True)
