FROM swift:5.9-jammy

# Install dependencies for PDF/image processing
RUN apt-get update && apt-get install -y \
    poppler-utils \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Fix ImageMagick security policy to allow PDF operations
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml

WORKDIR /app
COPY . .

RUN swift build -c release

ENTRYPOINT [".build/release/scanify"]
