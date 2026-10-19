// Loads MagicStream's sample data (src/magic-stream-seed-data) into an empty database.
// Run by the `seed` service in compose.yml with mongosh. It only fills collections that are
// empty, so restarting the stack never duplicates or overwrites anything.
const fs = require("fs");
const dir = "/seed-data";
const target = db.getSiblingDB(process.env.DATABASE_NAME || "magicstream");

for (const name of ["genres", "rankings", "movies", "users"]) {
  const coll = target.getCollection(name);
  if (coll.countDocuments() > 0) {
    print(`${name}: already has ${coll.countDocuments()} documents, left alone`);
    continue;
  }
  const docs = EJSON.parse(fs.readFileSync(`${dir}/${name}.json`, "utf8"));
  coll.insertMany(docs);
  print(`${name}: inserted ${docs.length}`);
}
