-- Test SQL database for malware pattern scanning
-- Table: comments
CREATE TABLE comments (
    author TEXT,
    content TEXT
);

INSERT INTO comments (author, content) VALUES
    ('normaluser', 'This is a safe comment.'),
    ('base64_decode(virus)', 'All good here.'),
    ('http://spammer.com', 'Get more spam at: http://spammer.com'),
    ('bob', 'Try wget http://malicious.com');

-- Table: reviews
CREATE TABLE reviews (
    author TEXT,
    content TEXT
);

INSERT INTO reviews (author, content) VALUES
    ('HTTP://spammer.com', 'Nice product!'),
    ('alice', '<script>run_malware()</script>'),
    ('base64_decode(virus)', '<script>run_malware()</script>'),
    ('joe', 'I loved it!');
