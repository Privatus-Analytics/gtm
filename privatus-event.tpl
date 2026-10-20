___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Privatus Analytics – Event",
  "categories": [
    "ANALYTICS",
    "CONVERSIONS"
  ],
  "brand": {
    "id": "brand_privatus_analytics",
    "displayName": "Privatus Analytics",
    "thumbnail": ""
  },
  "description": "Send a custom event (with properties and optional revenue) to Privatus Analytics via privatus.track(). Requires the pa.js tracker on the page; calls made before it loads are queued.",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "eventName",
    "displayName": "Event name",
    "simpleValueType": true,
    "help": "Up to 120 characters, e.g. Signup, purchase, Download.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "STRING_LENGTH",
        "args": [
          1,
          120
        ]
      }
    ]
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "props",
    "displayName": "Properties",
    "simpleTableColumns": [
      {
        "defaultValue": "",
        "displayName": "Key",
        "name": "key",
        "type": "TEXT",
        "valueValidators": [
          {
            "type": "REGEX",
            "args": [
              "^[a-z0-9_]{1,64}$"
            ],
            "errorMessage": "Keys: lowercase letters, digits and _ (max 64)."
          }
        ]
      },
      {
        "defaultValue": "",
        "displayName": "Value",
        "name": "value",
        "type": "TEXT"
      }
    ],
    "help": "Up to 30 properties. Never put personal data (emails, names, ids) in properties. Numeric strings are sent as numbers, 'true'/'false' as booleans."
  },
  {
    "type": "GROUP",
    "name": "revenueGroup",
    "displayName": "Revenue",
    "groupStyle": "ZIPPY_OPEN_ON_PARAM",
    "subParams": [
      {
        "type": "TEXT",
        "name": "revenue",
        "displayName": "Revenue (major units, e.g. 49.99)",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "DECIMAL"
          }
        ]
      },
      {
        "type": "TEXT",
        "name": "currency",
        "displayName": "Currency (ISO 4217)",
        "simpleValueType": true,
        "defaultValue": "USD",
        "valueValidators": [
          {
            "type": "REGEX",
            "args": [
              "^[A-Za-z]{3}$"
            ]
          }
        ]
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "namespace",
    "displayName": "Tracker namespace",
    "simpleValueType": true,
    "defaultValue": "privatus",
    "help": "Only change this if pa.js uses data-namespace, and update the 'Accesses global variables' permission to match."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

// Privatus Analytics – Event (MIT OR Apache-2.0)
// Calls privatus.track(name, props) when the tracker (or its queue stub) is present; otherwise creates the queue
// window.privatus.q and pushes ['track', [name, props]], which pa.js replays when it loads.
const copyFromWindow = require('copyFromWindow');
const callInWindow = require('callInWindow');
const setInWindow = require('setInWindow');
const createQueue = require('createQueue');
const makeTableMap = require('makeTableMap');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const logToConsole = require('logToConsole');
const Object = require('Object');

const MAX_PROPS = 30;
const KEY_CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789_';

const validKey = (key) => {
  if (!key || key.length > 64) return false;
  for (let i = 0; i < key.length; i++) {
    if (KEY_CHARS.indexOf(key.charAt(i)) < 0) return false;
  }
  return true;
};

const coerce = (value) => {
  const str = makeString(value);
  if (str === 'true') return true;
  if (str === 'false') return false;
  const num = makeNumber(str);
  if (str.trim() !== '' && makeString(num) === str) return num;
  return str.length > 500 ? str.substring(0, 500) : str;
};

const ns = makeString(data.namespace || 'privatus');
const name = makeString(data.eventName || '').substring(0, 120);

if (!name) {
  logToConsole('[privatus] missing event name');
  data.gtmOnFailure();
} else {
  const props = {};
  const table = data.props ? makeTableMap(data.props, 'key', 'value') : {};
  let count = 0;
  Object.keys(table || {}).forEach((key) => {
    if (count >= MAX_PROPS || key === 'revenue' || key === 'currency') return;
    if (!validKey(key)) {
      logToConsole('[privatus] dropping invalid property key', key);
      return;
    }
    props[key] = coerce(table[key]);
    count++;
  });

  if (data.revenue !== undefined && makeString(data.revenue) !== '') {
    const revenue = makeNumber(data.revenue);
    if (revenue === revenue) { // not NaN
      props.revenue = revenue;
      props.currency = makeString(data.currency || 'USD').toUpperCase();
    }
  }

  if (typeof copyFromWindow(ns + '.track') === 'function') {
    callInWindow(ns + '.track', name, props);
  } else {
    if (!copyFromWindow(ns)) setInWindow(ns, {}, false);
    const push = createQueue(ns + '.q');
    push(['track', [name, props]]);
  }
  data.gtmOnSuccess();
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "privatus"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "privatus.q"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "privatus.track"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Calls privatus.track when the tracker is present
  code: |-
    mock('copyFromWindow', (key) => key === 'privatus.track' ? (() => {}) : undefined);
    runCode(mockData);
    assertApi('callInWindow').wasCalledWith('privatus.track', 'Signup', {plan: 'pro', seats: 3, trial: true});
    assertApi('createQueue').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: Queues the call when the tracker has not loaded yet
  code: |-
    let pushed;
    mock('copyFromWindow', () => undefined);
    mock('createQueue', (key) => { assertThat(key).isEqualTo('privatus.q'); return (item) => { pushed = item; }; });
    runCode(mockData);
    assertApi('setInWindow').wasCalledWith('privatus', {}, false);
    assertThat(pushed).isEqualTo(['track', ['Signup', {plan: 'pro', seats: 3, trial: true}]]);
    assertApi('gtmOnSuccess').wasCalled();
- name: Adds revenue and currency
  code: |-
    mock('copyFromWindow', (key) => key === 'privatus.track' ? (() => {}) : undefined);
    mockData.eventName = 'purchase';
    mockData.props = [];
    mockData.revenue = '49.99';
    mockData.currency = 'eur';
    runCode(mockData);
    assertApi('callInWindow').wasCalledWith('privatus.track', 'purchase', {revenue: 49.99, currency: 'EUR'});
- name: Drops invalid property keys
  code: |-
    mock('copyFromWindow', (key) => key === 'privatus.track' ? (() => {}) : undefined);
    mockData.props = [{key: 'Bad Key', value: 'x'}, {key: 'ok', value: '007'}];
    runCode(mockData);
    assertApi('callInWindow').wasCalledWith('privatus.track', 'Signup', {ok: '007'});
setup: |-
  const mockData = {
    eventName: 'Signup',
    props: [{key: 'plan', value: 'pro'}, {key: 'seats', value: '3'}, {key: 'trial', value: 'true'}],
    currency: 'USD',
    namespace: 'privatus'
  };
  mock('setInWindow', () => true);


___NOTES___

Created for Privatus Analytics. Requires pa.js on the page (site snippet or a Custom HTML tag).
