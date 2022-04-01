rs.initiate()
var cfg = rs.config();
cfg.members = [{ _id: 0, host: 'mongo1-www', priority: 10 }]
rs.reconfig(cfg, { force: true })
rs.add({ _id: 2, host: 'mongo2-www', priority: 5 })
rs.add({ _id: 3, host: 'mongo3-www', priority: 2 })
db = db.getSiblingDB('analytics')
db.createUser({ user: 'saprdwww', pwd: 'password', roles: [{ role: 'readWrite', db: 'analytics' }] })
db = db.getSiblingDB('tracking_live')
db.createUser({ user: 'saprdwww', pwd: 'password', roles: [{ role: 'readWrite', db: 'tracking_live' }] })
db = db.getSiblingDB('tracking_history')
db.createUser({ user: 'saprdwww', pwd: 'password', roles: [{ role: 'readWrite', db: 'tracking_history' }] })
db = db.getSiblingDB('tracking_contact')
db.createUser({ user: 'saprdwww', pwd: 'password', roles: [{ role: 'readWrite', db: 'tracking_contact' }] })