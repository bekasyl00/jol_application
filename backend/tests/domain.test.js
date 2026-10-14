const {test} = require("node:test");
const assert = require("node:assert/strict");
const D = require("../functions/domain");
const valid = () => ({id: "order-1", fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: "box", weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: Date.now() + 3600000, addressFrom: "Дом 1", addressTo: "Дом 2", recipientName: "Алия", recipientPhone: "+77011234567", comment: "Хрупкое"});
test("pricing and finite bounds", () => {
  assert.equal(D.quote(100, 0.06), 2100);
  for (const distance of [NaN, Infinity, -1, 5001]) assert.throws(() => D.quote(distance, 0.06));
});
test("private contact fields never enter the market document", () => {
  const {order, details} = D.validateOrder(valid());
  assert.equal(order.recipientPhone, undefined); assert.equal(order.addressFrom, undefined);
  assert.equal(details.recipientPhone, "+77011234567");
});
test("reject malformed orders", () => {
  for (const patch of [{fromCity: "Москва"}, {toCity: "Алматы"}, {weight: NaN}, {recipientPhone: "7000"}, {price: 1.5}, {id: "../users/x"}, {pickupAt: 0}, {itemDescription: ""}]) assert.throws(() => D.validateOrder({...valid(), ...patch}));
});
test("only eligible courier may accept waiting order", () => {
  const order = {senderId: "sender", driverId: null, status: "waiting", weight: 10};
  D.authorizeAccept(order, {role: "courier", capacityKg: 20}, "driver");
  assert.throws(() => D.authorizeAccept(order, {role: "sender"}, "sender"));
  assert.throws(() => D.authorizeAccept({...order, status: "accepted", driverId: "a"}, {role: "courier", capacityKg: 20}, "b"));
  assert.throws(() => D.authorizeAccept(order, {role: "courier", capacityKg: 5}, "driver"));
});
test("status cannot skip stages or be changed by outsider", () => {
  const order = {senderId: "sender", driverId: "driver", status: "accepted"};
  assert.equal(D.authorizeTransition(order, "driver", "enRoute").status, "enRoute");
  for (const uid of ["sender", "outsider"]) assert.throws(() => D.authorizeTransition(order, uid, "pickedUp"));
  assert.throws(() => D.authorizeTransition(order, "driver", "delivered"));
  assert.throws(() => D.authorizeTransition({...order, status: "pickedUp"}, "sender", "cancelled", "Причина"));
  assert.throws(() => D.authorizeTransition(order, "sender", "cancelled", ""));
  assert.equal(D.authorizeTransition(order, "sender", "cancelled", "Планы изменились").status, "cancelled");
});
test("contact and chat authorization", () => {
  D.participant({senderId: "s", driverId: "d"}, "d");
  assert.throws(() => D.participant({senderId: "s", driverId: "d"}, "x"));
  assert.throws(() => D.text("x".repeat(2001), "message", 1, 2000));
});

test("map points remain private and marketplace only contains coarse cells", () => {
 const input = {...valid(), pickupAt: Date.now() + 3600000, pickupPlace: {coordinate: {latitude: 43.2383, longitude: 76.9455}, label: "Private street"}, dropoffPlace: {coordinate: {latitude: 51.1282, longitude: 71.4304}, label: "Private house"}, distanceSource: "unavailable", distanceKm: 0};
 const result = D.validateOrder(input);
 assert.deepEqual(result.order.pickupArea, {latitude: 43.2, longitude: 76.9});
 assert.equal(result.order.recommendedPrice, null);
 assert.equal(result.order.pickupPlace, undefined);
 assert.equal(result.details.pickupPlace.label, "Private street");
 assert.throws(() => D.validateOrder({...input, pickupPlace: {...input.pickupPlace, coordinate: {latitude: 100, longitude: 0}}}));
 assert.throws(() => D.validateOrder({...input, distanceSource: "manualDemo"}));
 assert.throws(() => D.validateOrder({...input, distanceSource: "appleMapKit", distanceKm: 100}));
});
