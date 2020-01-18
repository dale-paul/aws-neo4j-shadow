from neo4j import GraphDatabase

driver = GraphDatabase.driver("bolt://localhost:7687")

def make_node(tx,args):
    return tx.run(
        statement=
            "MERGE (n:" f"{args['label']}" " {name:{properties}.name}) ON CREATE set n={properties}",
        parameters={'properties':args['properties']}
        )

def make_rel(tx,n1,rel,n2):
    tx.run(
        statement=
            "MATCH (n1:" f"{n1['label']}" "{name:$n1}) "
            "MATCH (n2:" f"{n2['label']}" "{name:$n2}) "
            "MERGE (n1)-[r:" f"{rel['label']}" "]->(n2) ON CREATE set r={properties}",
        parameters={
                    'n1':n1['properties']['name'],
                    'properties':rel['properties'],
                    'n2':n2['properties']['name']
                    }
    )


with driver.session() as session:
    session.run("create constraint on (n:Label) assert n.name is unique;")
    tx = session.begin_transaction()
    make_node(tx,{'label':'IAM:USER','properties':{'name':'PW9E','role':'ADMIN'}})
    make_node(tx,{'label':'IAM:POLICY','properties':{'name':'ADMIN'}})
    make_rel(tx,   {'label':'IAM:USER','properties':{'name':'PW9E'}},
                    {'label':'HAS_POLICY','properties':{'when':'today'}},
                    {'label':'IAM:POLICY','properties':{'name':'ADMIN'}}
                )
    tx.commit()

driver.close()