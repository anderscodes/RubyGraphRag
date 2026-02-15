.PHONY: neo4j-up neo4j-down neo4j-ps neo4j-logs

neo4j-up:
	docker compose -f docker-compose.neo4j.yml up -d

neo4j-down:
	docker compose -f docker-compose.neo4j.yml down

neo4j-ps:
	docker compose -f docker-compose.neo4j.yml ps

neo4j-logs:
	docker compose -f docker-compose.neo4j.yml logs -f neo4j
