var express = require('express');
var app = express();
var bodyParser = require('body-parser');

app.use(bodyParser.json()); // this will parse Content-Type: application/json
app.use(bodyParser.urlencoded({ extended: true})); // this will parse Content-Type: application/x-www-form-urlencoded

module.exports = app;