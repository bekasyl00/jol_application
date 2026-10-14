"use strict";
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const D = require("./domain");
const fail = message => { throw new D.DomainError("failed-precondition", message); };
function validateTrip(input, p, uid, now = Date.now()) {
  if (p.role !== "courier") throw new D.DomainError("permission-denied", "Поездки публикует перевозчик.");
  if (!D.cities.includes(input.fromCity) || !D.cities.includes(input.toCity) || input.fromCity === input.toCity) fail("Выберите разные города.");
  const origin = D.place(input.origin), destination = D.place(input.destination);
  const departureAt = D.number(input.departureAt, "дата", now - 300000, now + 366 * 86400000);
  const capacityKg = D.number(input.capacityKg, "вместимость", 0.1, p.capacityKg);
  const maxParcels = D.number(input.maxParcels, "количество посылок", 1, 10);
  const pickupWindowMinutes = D.number(input.pickupWindowMinutes, "окно передачи", 15, 1440);
  const maxDetourMinutes = D.number(input.maxDetourMinutes, "объезд в минутах", 0, 240);
  if (![maxParcels, pickupWindowMinutes, maxDetourMinutes].every(Number.isInteger)) fail("Укажите целое число.");
  return {
    trip: {id: D.id(input.id), driverId: uid, driverName: p.name, vehicle: p.vehicle, fromCity: input.fromCity, toCity: input.toCity,
      originArea: D.area(origin.coordinate), destinationArea: D.area(destination.coordinate), departureAt: Timestamp.fromMillis(departureAt),
      capacityKg, maxParcels, reservedKg: 0, acceptedCount: 0, version: 1, pickupWindowMinutes,
      maxDetourKm: D.number(input.maxDetourKm, "допустимый объезд", 0, 300), maxDetourMinutes, status: "published", createdAt: FieldValue.serverTimestamp()},
    details: {origin, destination, deliveryIds: []}
  };
}
function eligible(trip, order, now = Date.now()) {
  if (trip.status !== "published" || trip.departureAt.toMillis() <= now || order.status !== "waiting" || order.driverId) fail("Заказ или поездка уже недоступны.");
  if (order.senderId === trip.driverId || order.weight > trip.capacityKg - trip.reservedKg || trip.acceptedCount >= trip.maxParcels) fail("В поездке недостаточно свободного места.");
  if (Math.abs(order.pickupAt.toMillis() - trip.departureAt.toMillis()) > trip.pickupWindowMinutes * 60000) fail("Не подходит время передачи посылки.");
}
function proposalID(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,260}$/.test(value)) throw new D.DomainError("invalid-argument", "Некорректное предложение.");
  return value;
}
function handlers({db, callable, profile, existing}) {
  const ref = id => db.doc(`trips/${D.id(id)}`);
  const pRef = id => db.doc(`proposals/${proposalID(id)}`);
  return {
    publishTrip: callable(async (uid, data) => {
      const target = ref(data.id);
      await db.runTransaction(async tx => {
        const p = await profile(uid, tx); const old = await tx.get(target);
        if (old.exists) { if (old.data().driverId !== uid) fail("ID поездки занят."); return; }
        const active = await tx.get(db.collection("trips").where("driverId", "==", uid).where("status", "==", "published"));
        if (active.docs.filter(s => s.data().departureAt.toMillis() > Date.now()).length >= 10) fail("Сначала закройте одну из опубликованных поездок.");
        const {trip, details} = validateTrip(data, p, uid);
        tx.create(target, trip); tx.create(target.collection("private").doc("details"), details);
      });
      return {id: target.id};
    }),
    closeTrip: callable(async (uid, data) => {
      await db.runTransaction(async tx => {
        await profile(uid, tx); const target = ref(data.id), trip = existing(await tx.get(target));
        if (trip.driverId !== uid) throw new D.DomainError("permission-denied", "Это чужая поездка.");
        if (trip.status === "closed") return;
        const pending = await tx.get(db.collection("proposals").where("tripId", "==", data.id).where("status", "==", "pending"));
        tx.update(target, {status: "closed", version: trip.version + 1});
        pending.docs.forEach(s => tx.update(s.ref, {status: "expired"}));
      });
      return {ok: true};
    }),
    createProposal: callable(async (uid, data) => {
      const tripId = D.id(data.tripId), deliveryId = D.id(data.deliveryId), target = pRef(deliveryId + "_" + tripId);
      await db.runTransaction(async tx => {
        const user = await profile(uid, tx);
        const trip = existing(await tx.get(ref(tripId))), order = existing(await tx.get(db.doc(`deliveries/${deliveryId}`)));
        if (user.role !== "sender" || order.senderId !== uid) throw new D.DomainError("permission-denied", "Предложите свой заказ.");
        const old = await tx.get(target); if (old.exists) return;
        await profile(trip.driverId, tx);
        eligible(trip, order);
        const pendingOrder = await tx.get(db.collection("proposals").where("deliveryId", "==", deliveryId).where("status", "==", "pending"));
        const pendingTrip = await tx.get(db.collection("proposals").where("tripId", "==", tripId).where("status", "==", "pending"));
        if (pendingOrder.size >= 20 || pendingTrip.size >= 100) fail("Слишком много ожидающих предложений. Дождитесь ответа.");
        const {itemDescription, fromCity, toCity, weight, price, pickupAt} = order;
        tx.create(target, {id: target.id, tripId, deliveryId, senderId: uid, driverId: trip.driverId, itemDescription, fromCity, toCity, weight, price, pickupAt,
          ...(order.pickupArea ? {pickupArea: order.pickupArea, dropoffArea: order.dropoffArea} : {}), status: "pending", createdAt: FieldValue.serverTimestamp()});
        // The trip write serializes proposal count limits against other senders and closing.
        tx.update(ref(tripId), {version: trip.version + 1});
        tx.update(db.doc(`deliveries/${deliveryId}`), {proposalRevision: (order.proposalRevision || 0) + 1});
      });
      return {id: target.id};
    }),
    respondProposal: callable(async (uid, data) => {
      const target = pRef(data.id), action = data.action;
      if (!["accepted", "rejected", "withdrawn"].includes(action)) fail("Неизвестное действие.");
      await db.runTransaction(async tx => {
        await profile(uid, tx); const proposal = existing(await tx.get(target));
        if (action === "withdrawn" ? proposal.senderId !== uid : proposal.driverId !== uid) throw new D.DomainError("permission-denied", "Нет доступа к предложению.");
        if (proposal.status === action) return;
        if (proposal.status !== "pending") fail("Предложение уже обработано.");
        const tripRef = ref(proposal.tripId), orderRef = db.doc(`deliveries/${proposal.deliveryId}`);
        const trip = existing(await tx.get(tripRef)), order = existing(await tx.get(orderRef));
        if (action === "accepted") {
          await profile(proposal.senderId, tx);
          eligible(trip, order);
          if (data.version !== trip.version) fail("Поездка изменилась. Обновите данные и оцените объезд заново.");
          const detailsRef = tripRef.collection("private").doc("details"), details = existing(await tx.get(detailsRef));
          const other = await tx.get(db.collection("proposals").where("deliveryId", "==", proposal.deliveryId).where("status", "==", "pending"));
          tx.update(orderRef, {driverId: uid, tripId: trip.id, status: "accepted", updatedAt: FieldValue.serverTimestamp()});
          tx.update(tripRef, {reservedKg: trip.reservedKg + order.weight, acceptedCount: trip.acceptedCount + 1, version: trip.version + 1});
          tx.update(detailsRef, {deliveryIds: [...details.deliveryIds, order.id]});
          other.docs.filter(s => s.id !== target.id).forEach(s => tx.update(s.ref, {status: "expired"}));
        }
        tx.update(target, {status: action});
      });
      return {ok: true};
    })
  };
}
module.exports = {handlers, validateTrip, eligible};
