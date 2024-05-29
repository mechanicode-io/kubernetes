import os
import socket

from flask import Flask, request, make_response, redirect, url_for
from flask import render_template

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


# Handle all other paths by returning a generic response
@app.route("/<string:path>")
def catch_all(path):
    # Consider a more informative message here
    return make_response({'msg': 'This is the root path'}, 200)


if __name__ == '__main__':
    print(f'Ready to receive requests on {config.PORT}')
    app.run(host='0.0.0.0', port=config.PORT, threaded=True)
