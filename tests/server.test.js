const request = require('supertest');
const app = require('../server');

describe('Quotes API', () => {
    let server;
    let quoteId;

    beforeAll(async () => {
        server = app.listen(3000); // Start the server before tests
    });

    afterAll(async () => {
        await server.close(); // Close the server after tests
    });

    it('should create a new quote', async () => {
        const res = await request(app)
            .post('/api/quotes')
            .send({ text: 'Life is what happens when you’re busy making other plans.', author: 'John Lennon' });
        expect(res.statusCode).toEqual(201);
        expect(res.body).toHaveProperty('id');
        quoteId = res.body.id; // Save the quote ID for further tests
    });

    it('should retrieve all quotes', async () => {
        const res = await request(app).get('/api/quotes');
        expect(res.statusCode).toEqual(200);
        expect(res.body.length).toBeGreaterThan(0);
    });

    it('should retrieve a single quote by ID', async () => {
        const res = await request(app).get(`/api/quotes/${quoteId}`);
        expect(res.statusCode).toEqual(200);
        expect(res.body.text).toBe('Life is what happens when you’re busy making other plans.');
    });

    it('should update a quote', async () => {
        const res = await request(app)
            .put(`/api/quotes/${quoteId}`)
            .send({ text: 'Life is beautiful.', author: 'Updated Author' });
        expect(res.statusCode).toEqual(200);
        expect(res.body.author).toBe('Updated Author');
    });

    it('should delete a quote', async () => {
        const res = await request(app).delete(`/api/quotes/${quoteId}`);
        expect(res.statusCode).toEqual(204);
    });

    it('should return 404 for non-existent quote', async () => {
        const res = await request(app).get(`/api/quotes/${quoteId}`);
        expect(res.statusCode).toEqual(404);
    });
});
