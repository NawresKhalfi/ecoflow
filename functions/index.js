/**
 * EcoFlow – Cloud Functions (plan Blaze requis, non déployées).
 *
 * sendNotification : à chaque document `notifications/{id}` écrit par
 * l'application, envoie un push FCM aux appareils du destinataire
 * (`fcmTokens`), dans sa langue et selon ses préférences. Si l'événement est
 * critique (arrivée, annulation) et qu'aucun push n'a pu être remis, envoie
 * un SMS de secours via Twilio (US-068), si les secrets sont configurés.
 *
 * Déploiement : firebase functions:secrets:set TWILIO_SID (…TOKEN, …FROM)
 *               firebase deploy --only functions
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { title, allowed, route } = require('./messages');

admin.initializeApp();
const db = admin.firestore();

const TWILIO_SID = defineSecret('TWILIO_SID');
const TWILIO_TOKEN = defineSecret('TWILIO_TOKEN');
const TWILIO_FROM = defineSecret('TWILIO_FROM');

async function sendSms(to, body) {
  const sid = TWILIO_SID.value();
  if (!sid || !to) return false;
  const auth = Buffer.from(`${sid}:${TWILIO_TOKEN.value()}`).toString('base64');
  const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ To: to, From: TWILIO_FROM.value(), Body: body }),
  });
  return res.ok;
}

exports.sendNotification = onDocumentCreated(
  { document: 'notifications/{id}', region: 'europe-west1', secrets: [TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM] },
  async (event) => {
    const n = event.data.data();
    const user = (await db.doc(`users/${n.toUid}`).get()).data() || {};
    if (user.status === 'deleted' || !allowed(n.type, user.notificationPreferences)) {
      return event.data.ref.update({ delivery: 'skipped' });
    }
    const lang = user.languageCode || 'fr';
    const heading = title(n.type, lang);
    const body = n.type === 'message' && n.preview ? n.preview : (n.address || '');
    const tokens = (await db.collection('fcmTokens').where('uid', '==', n.toUid).get()).docs.map((d) => d.id);

    let delivered = 0;
    if (tokens.length) {
      const res = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: heading, body },
        data: { route: route(n.type, n.collectionId, user.role), type: n.type },
        android: { priority: 'high', notification: { sound: 'default' } },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      delivered = res.successCount;
      // Jetons expirés : supprimés.
      await Promise.all(res.responses.map((r, i) =>
        !r.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']
          .includes(r.error && r.error.code) ? db.doc(`fcmTokens/${tokens[i]}`).delete() : null));
    }

    let sms = false;
    if (delivered === 0 && n.critical) sms = await sendSms(user.phoneNumber, `EcoFlow – ${heading} ${body}`.trim());
    return event.data.ref.update({ delivery: delivered > 0 ? 'push' : (sms ? 'sms' : 'none'), deliveredAt: new Date() });
  },
);
