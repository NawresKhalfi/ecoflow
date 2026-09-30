const assert = require('node:assert');
const test = require('node:test');
const { title, allowed, route } = require('./messages');

test('localized titles with French fallback', () => {
  assert.equal(title('arrived', 'en'), 'The collector has arrived 📍');
  assert.equal(title('arrived', 'de'), 'Le collecteur est arrivé 📍');
});

test('preferences: messages always allowed, statuses follow the toggle', () => {
  assert.equal(allowed('message', { collectionStatus: false }), true);
  assert.equal(allowed('arrived', { collectionStatus: false }), false);
  assert.equal(allowed('arrived', undefined), true);
});

test('deep links match the app routes', () => {
  assert.equal(route('newMission', 'c1', 'collector'), '/app/missions/c1');
  assert.equal(route('arrived', 'c1', 'citizen'), '/app/collections/c1');
  assert.equal(route('message', 'c1', 'citizen'), '/app/chat/c1');
});
