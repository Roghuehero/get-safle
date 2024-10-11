const express = require('express');
const app = express();
const bodyParser = require('body-parser');

// Middleware to parse JSON
app.use(bodyParser.json());

// In-memory quotes array for demo purposes
let quotes = [];

// Route to create a new quote
app.post('/api/quotes', (req, res) => {
    const { text, author } = req.body;
    const newQuote = { id: quotes.length + 1, text, author };
    quotes.push(newQuote);
    res.status(201).json(newQuote);
});

// Route to retrieve all quotes
app.get('/api/quotes', (req, res) => {
    res.status(200).json(quotes);
});

// Route to retrieve a single quote by ID
app.get('/api/quotes/:id', (req, res) => {
    const quote = quotes.find(q => q.id === parseInt(req.params.id));
    if (!quote) return res.status(404).send('Quote not found.');
    res.status(200).json(quote);
});

// Route to update a quote
app.put('/api/quotes/:id', (req, res) => {
    const quote = quotes.find(q => q.id === parseInt(req.params.id));
    if (!quote) return res.status(404).send('Quote not found.');

    const { text, author } = req.body;
    quote.text = text;
    quote.author = author;
    res.status(200).json(quote);
});

// Route to delete a quote
app.delete('/api/quotes/:id', (req, res) => {
    const index = quotes.findIndex(q => q.id === parseInt(req.params.id));
    if (index === -1) return res.status(404).send('Quote not found.');

    quotes.splice(index, 1);
    res.status(204).send();
});

// Start the server if the file is executed directly
if (require.main === module) {
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
        console.log(`Server is running on port ${PORT}`);
    });
}

// Export the app for testing
module.exports = app;
