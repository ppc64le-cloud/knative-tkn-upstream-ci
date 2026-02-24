

| Job name                                                        | Time taken (mins) | Job schedule     | CI Enabled ?   |
| --------------------------------------------------------------- |:-----------------:|:----------------:| -------------: | 
| knative-eventing-reconciler-main-periodic                       | 90                | 0 0 * * *	 | ❌             |
| knative-eventing-reconciler-release-1.20-periodic               | 90	              | 0 1 * * *	 | ❌             |
| knative-client-main-periodic                                    | 90	              | 0 2 * * *	 | ✅             |
| knative-client-release-1.20-periodic                            | 90	              | 0 3 * * *	 | ✅             |
| knative-eventing-main-periodic                                  | 90	              | 0 4 * * *	 | ✅             |
| knative-eventing-release-1.20-periodic                          | 90	              | 0 5 * * *	 | ✅ 	           |
| knative-operator-main-periodic                                  | 60	              | 0 6 * * *	 | ✅             |
| knative-operator-release-1.20-periodic                          | 60	              | 0 7 * * *	 | ✅             |
| knative-sasl-plain-eventing-kafka-broker-main-periodic          | 90	              | 0 8 * * *	 | ✅             |
| knative-sasl-plain-eventing-kafka-broker-release-1.20-periodic  | 90		      | 0 9 * * *	 | ✅             |
| knative-sasl-ssl-eventing-kafka-broker-main-periodic            | 90	              | 0 10 * * *	 | ✅             |
| knative-sasl-ssl-eventing-kafka-broker-release-1.20-periodic    | 90		      | 0 11 * * *	 | ✅             |
| knative-ssl-eventing-kafka-broker-main-periodic                 | 90		      | 0 12 * * *	 | ✅             |
| knative-ssl-eventing-kafka-broker-release-1.20-periodic         | 90	      	      | 0 13 * * *	 | ✅             |
| knative-plugin-event-main-periodic                              | 60		      | 0 14 * * *	 | ✅             |
| knative-plugin-event-release-1.20-periodic                      | 60		      | 0 15 * * *	 | ✅             |
| knative-serving-kourier-main-periodic                           | 180		      | 0 16 * * *	 | ❌             |
| knative-serving-kourier-release-1.20-periodic                   | 180		      | 0 17 * * *	 | ❌             |
