const allowedEvents = new Set([
  "pairing_success", "pairing_failure", "first_transfer", "transfer_failure",
  "update_check", "update_available", "update_opened", "update_failure",
]);

module.exports = function handler(request, response) {
  if (request.method !== "POST") return response.status(405).end();
  const body = request.body;
  const keys = body && typeof body === "object" ? Object.keys(body).sort() : [];
  if (keys.join() !== "appVersion,counts,osMajor,platform,schemaVersion" ||
      body.schemaVersion !== 1 || !["android", "macos"].includes(body.platform) ||
      !/^\d+$/.test(body.osMajor) || !/^[0-9A-Za-z.-]{1,32}$/.test(body.appVersion) ||
      !body.counts || typeof body.counts !== "object" || Array.isArray(body.counts) ||
      Object.entries(body.counts).some(([name, count]) =>
        !allowedEvents.has(name) || !Number.isInteger(count) || count < 1 || count > 10000)) {
    return response.status(400).end();
  }

  console.log(JSON.stringify(body));
  return response.status(204).end();
};
