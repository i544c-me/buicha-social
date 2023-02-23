function handler(event) {
    if (event.viewer.ip == "126.89.42.68") {
        return event.response;
    }

    var response = {
        statusCode: 302,
        statusDescription: '302 Found',
        headers: {
            'cloudfront-functions': { value: 'generated-by-CloudFront-Functions' },
            'location': { value: 'https://buicha.social/files/maintenance.html' },
        }
    };
    return response;
}