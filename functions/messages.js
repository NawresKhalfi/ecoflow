// Textes des notifications, dans la langue du destinataire (fr / en / ar).
const TITLES = {
  fr: {
    assigned: 'Collecteur trouvé 🚚', onTheWay: 'Le collecteur est en route', arrived: 'Le collecteur est arrivé 📍',
    handedOver: 'Pesée enregistrée : confirme la remise', completed: 'Collecte confirmée par le citoyen ✅',
    cancelled: 'Collecte annulée', newMission: 'Nouvelle mission près de toi 🔔', message: 'Nouveau message 💬',
  },
  en: {
    assigned: 'Collector found 🚚', onTheWay: 'The collector is on the way', arrived: 'The collector has arrived 📍',
    handedOver: 'Weighing saved: confirm the handover', completed: 'Pickup confirmed by the citizen ✅',
    cancelled: 'Pickup cancelled', newMission: 'New mission near you 🔔', message: 'New message 💬',
  },
  ar: {
    assigned: 'تم إيجاد جامع 🚚', onTheWay: 'الجامع في الطريق', arrived: 'وصل الجامع 📍',
    handedOver: 'تم الوزن: أكّد التسليم', completed: 'أكّد المواطن عملية الجمع ✅',
    cancelled: 'أُلغيت عملية الجمع', newMission: 'مهمة جديدة بالقرب منك 🔔', message: 'رسالة جديدة 💬',
  },
};

function title(type, lang) {
  return (TITLES[lang] || TITLES.fr)[type] || TITLES.fr[type] || 'EcoFlow';
}

// Préférences US-009 : les messages passent toujours, le reste dépend de
// « statut de mes collectes ».
function allowed(type, prefs) {
  if (type === 'message') return true;
  return !prefs || prefs.collectionStatus !== false;
}

// Écran à ouvrir au toucher (ouverture directe, US-066).
function route(type, collectionId, role) {
  if (type === 'message') return `/app/chat/${collectionId}`;
  return role === 'collector' ? `/app/missions/${collectionId}` : `/app/collections/${collectionId}`;
}

module.exports = { title, allowed, route };
