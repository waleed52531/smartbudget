// Contract-based local stand-in for Google's public Firebase Auth key endpoint.
// No credentials or user data are accepted, stored, or returned.
const http = require('node:http');
http.createServer((request, response) => {
  response.setHeader('content-type', 'application/json');
  if (request.method === 'GET' && request.url.split('?')[0] === '/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com') {
    response.statusCode = 503;
    response.end(JSON.stringify({error: {code: 503, status: 'UNAVAILABLE', message: 'Synthetic key-service outage'}}));
  } else {
    response.statusCode = 501;
    response.end(JSON.stringify({error: {code: 501, status: 'UNIMPLEMENTED'}}));
  }
}).listen(process.env.PORT);
