/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall,HttpsError} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// The Firebase Admin SDK to access Firestore.
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();


exports.clearBeingEditedBy = onCall(async (request) => {
  // 1. Check if the user is authenticated
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // 2. Extract arguments passed from Flutter
  const { docPath, force } = request.data;
  const activeUserEmail = request.auth.token.email; // Securely get user ID from token, not client payload

  if (!docPath) {
    throw new HttpsError("invalid-argument", "The function must be called with a valid 'docPath'. Passed: " + docPath);
  }

  try {
    const scoreDocRef = db.doc(docPath);

    // 3. Run the transaction natively on the server
    const success = await db.runTransaction(async (transaction) => {
      const freshScoreDoc = await transaction.get(scoreDocRef);

      if (!freshScoreDoc.exists) {
        return false;
      }

      const data = freshScoreDoc.data();
      const currentBeingEditedBy = data.BeingEditedBy || "";

      // 4. Verify ownership before clearing the lock
      if (currentBeingEditedBy === activeUserEmail || force) {
        transaction.update(scoreDocRef, { BeingEditedBy: "" });
        return true;
      }
      logger.log(`clearBeingEditedBy: User email ${activeUserEmail} does not match the current editor ${currentBeingEditedBy} for doc:${docPath}.`);
      return false;
    });

    return success;

  } catch (error) {
    console.error("Transaction failed:", error);
    throw new HttpsError("internal", "Failed to clear edit status due to a server error.");
  }
});

exports.setBeingEditedBy = onCall(async (request) => {
  // 1. Check if the user is authenticated
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // 2. Extract arguments passed from Flutter
  const { docPath } = request.data;
  const activeUserEmail = request.auth.token.email; // Securely get user ID from token, not client payload

  if (!docPath) {
    throw new HttpsError("invalid-argument", "The function must be called with a valid 'docPath'. Passed: " + docPath);
  }

  try {
    const scoreDocRef = db.doc(docPath);

    // 3. Run the transaction natively on the server
    const success = await db.runTransaction(async (transaction) => {
      const freshScoreDoc = await transaction.get(scoreDocRef);

      if (!freshScoreDoc.exists) {
        return false;
      }

      const data = freshScoreDoc.data();
      const currentBeingEditedBy = data.BeingEditedBy || "";

      // 4. Verify ownership before clearing the lock
      if (currentBeingEditedBy === "") {
        transaction.update(scoreDocRef, { BeingEditedBy: activeUserEmail });
        return true;
      }
      logger.log(`setBeingEditedBy: the current editor "${currentBeingEditedBy}" is not empty for doc:${docPath}.`);
      return false;
    });

    return success;

  } catch (error) {
    console.error("Transaction failed:", error);
    throw new HttpsError("internal", "Failed to set edit status due to a server error.");
  }
});
