"use strict";
class DomainError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (message) => { throw new DomainError("invalid-argument", message); };
function text(value, name, min = 1, max = 500) {
  if (typeof value !== "string" || value.trim().length < min || value.length > max) fail(`Проверьте поле: ${name}.`);
  return value.trim();
}
function number(value, name, min, max) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) fail(`Проверьте поле: ${name}.`);
  return value;
}
function id(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail("Некорректный ID.");
  return value;
}
function quote(distance, volume) {
  return Math.ceil(1000 + number(distance, "расстояние", 1, 5000) * 8 + number(volume, "объём", 0.001, 5) * 5000);
}
const cities = ["Алматы", "Астана", "Шымкент", "Караганда", "Тараз", "Актобе", "Атырау", "Актау", "Павлодар", "Семей", "Өскемен", "Костанай", "Кызылорда", "Петропавловск", "Уральск", "Талдыкорган"];
function validateOrder(input, now = Date.now()) {
  const orderId = id(input.id);
  if (!cities.includes(input.fromCity) || !cities.includes(input.toCity) || input.fromCity === input.toCity) fail("Выберите разные города из списка.");
  if (!["packet", "bag", "box", "suitcase"].includes(input.size)) fail("Неизвестный размер посылки.");
  const pickupPlace = input.pickupPlace == null ? null : place(input.pickupPlace);
  const dropoffPlace = input.dropoffPlace == null ? null : place(input.dropoffPlace);
  if (!!pickupPlace !== !!dropoffPlace) fail("Подтвердите обе точки.");
  const distanceSource = input.distanceSource || "legacy";
  if (!["legacy", "appleMapKit", "unavailable"].includes(distanceSource)) fail("Некорректный источник расстояния.");
  if (distanceSource !== "legacy" && !pickupPlace) fail("Подтвердите точки.");
  const distanceKm = number(input.distanceKm, "расстояние", distanceSource === "unavailable" ? 0 : 1, distanceSource === "unavailable" ? 0 : 5000);
  const route = input.route == null ? null : {
    distanceMeters: number(input.route.distanceMeters, "длина маршрута", 1, 5000000),
    durationSeconds: number(input.route.durationSeconds, "время пути", 1, 604800),
    calculatedAt: number(input.route.calculatedAt, "время расчёта", now - 86400000, now + 60000)
  };
  if (distanceSource === "appleMapKit" && (!route || Math.abs(Math.ceil(route.distanceMeters / 1000) - distanceKm) > 1)) fail("Обновите расчёт маршрута.");
  const volume = number(input.volume, "объём", 0.001, 5);
  const weight = number(input.weight, "вес", 0.1, 5000);
  const price = number(input.price, "цена", 1, 1000000);
  if (!Number.isInteger(price)) fail("Цена должна быть целым числом тенге.");
  const pickupAt = number(input.pickupAt, "дата", now - 300000, now + 366 * 86400000);
  const phone = text(input.recipientPhone, "телефон", 12, 12);
  if (!/^\+7\d{10}$/.test(phone)) fail("Телефон: +7XXXXXXXXXX.");
  const comment = typeof input.comment === "string" && input.comment.length <= 1000 ? input.comment.trim() : fail("Комментарий — до 1000 символов.");
  return {
    order: {id: orderId, fromCity: input.fromCity, toCity: input.toCity, itemDescription: text(input.itemDescription, "описание", 3), size: input.size, weight, volume, distanceKm, price, pickupAt, recommendedPrice: distanceSource === "unavailable" ? null : quote(distanceKm, volume), distanceSource, ...(pickupPlace ? {pickupArea: area(pickupPlace.coordinate), dropoffArea: area(dropoffPlace.coordinate)} : {})},
    details: {addressFrom: text(input.addressFrom, "адрес отправления"), addressTo: text(input.addressTo, "адрес получения"), recipientName: text(input.recipientName, "получатель", 1, 80), recipientPhone: phone, comment, ...(pickupPlace ? {pickupPlace, dropoffPlace} : {}), ...(route ? {route} : {})}
  };
}
function authorizeAccept(order, profile, uid) {
  if (profile.role !== "courier" || order.senderId === uid) throw new DomainError("permission-denied", "Заказ может принять перевозчик.");
  if (order.status !== "waiting" || order.driverId) throw new DomainError("already-exists", "Заказ уже принят.");
  if (profile.capacityKg < order.weight) fail("Недостаточная грузоподъёмность.");
}
const next = {accepted: "enRoute", enRoute: "pickedUp", pickedUp: "delivered"};
function authorizeTransition(order, uid, target, reason) {
  if (target === "cancelled") {
    if (![order.senderId, order.driverId].includes(uid) || !["waiting", "accepted", "enRoute"].includes(order.status)) throw new DomainError("permission-denied", "Отмена недоступна на этом этапе.");
    return {status: target, cancellationReason: text(reason, "причина отмены", 3)};
  }
  if (order.driverId !== uid || next[order.status] !== target) throw new DomainError("failed-precondition", "Обновите заказ: переход статуса недоступен.");
  return {status: target};
}
function participant(order, uid) {
  if (order.senderId !== uid && order.driverId !== uid) throw new DomainError("permission-denied", "Нет доступа к заказу.");
}
function point(value) {
  if (!value || typeof value !== "object") fail("Некорректная точка.");
  return {latitude: number(value.latitude, "широта", -90, 90), longitude: number(value.longitude, "долгота", -180, 180)};
}
function place(value) {
  if (!value || typeof value !== "object") fail("Некорректный адрес.");
  return {coordinate: point(value.coordinate), label: text(value.label, "адрес", 1, 500)};
}
function area(value) { return {latitude: Math.round(value.latitude * 10) / 10, longitude: Math.round(value.longitude * 10) / 10}; }
module.exports = {DomainError, point, place, area, cities, text, number, id, quote, validateOrder, authorizeAccept, authorizeTransition, participant};
