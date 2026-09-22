import redis
r = redis.Redis(host='localhost', port=46379, db=0, protocol=2)
r.set('test', 'value')
print(r.get('test'))  # b'value'
