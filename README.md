# Millenial

A sinatra interface to a redis-backed pub/sub system and worker system. This is still in alpha, it will probably not work as you expect it.

## Features
* Execute code by POST to the /create_task 
* Write to Redis by POST to /write 
* Read from Redis by a GET to /read
* Publish a JSON dictionary by POST to /stdout (may be used by pub/sub)
* Within the redis-cli you may publish via: PUBLISH channel payload

## Prerequisites
* Ruby-2.6.5
* rvm 1.29.9 or higher
* bundler gem version 1.17.3

## Installation

```sh
git clone <repository>
cd millenial
bundle install
rackup -p 4567
```

### Example: run a job that emits to the stdout channel
```sh
curl --location --request POST 'localhost:4567/create_task' \
--form 'source=emit :stdout, payload: {"key": "value"}
sleep 1
puts '\''tick'\''
sleep 1
puts "tock"'
```

### Example: Pretty print to the stdout and a channel
```sh
curl --location --request POST 'localhost:4567/stdout' \
--form 'aaa=bbb'
--form 'ccc=ddd'
--form 'channel=somechanneltopublishto'
```

#### Contact
Rodney Degracia
rdegraci@gmail.com

#### License

Copyright 2020 Rodney Degracia

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
  copies of the Software, and to permit persons to whom the Software is 
  furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.