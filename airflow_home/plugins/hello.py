from airflow.plugins_manager import AirflowPlugin
from flask_appbuilder import BaseView, expose

class HelloWorld(BaseView):
    route_base = "/hello"
    default_view = "world"

    @expose("/world")
    def world(self):
        return "<h1>Hello, world!</h1>"

view = {
    "category": "Extras",
    "name": "Hello",
    "view": HelloWorld(),
}

class HelloPlugin(AirflowPlugin):
    name = "Hello"
    appbuilder_views = [view]