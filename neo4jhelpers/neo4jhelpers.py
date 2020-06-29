from neo4j import GraphDatabase
import os
import dotenv
import logging

dotenv.find_dotenv(raise_error_if_not_found=True, usecwd=True)
dotenv.load_dotenv()

NEO4J_URI = os.environ['NEO4J_URI']

class Neo4jHelper():
    def __init__(self):
        logging.basicConfig(format='%(levelname)s: %(message)s', level='INFO')
        logging.info(f'Neo4j environment url is: {NEO4J_URI}')
        self._driver = GraphDatabase.driver(NEO4J_URI,encrypted=False)
        self._session = None

    def __del__(self):
        self._driver.close()

    def __enter__(self):
        self._session = self._driver.session()
        # self._session.run("create constraint on (n:Label) assert n.name is unique;")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._session.close()
        self._session = None

    #===================================
    # args MUST follow this form and at least include the label and name mappings
    # { 'label': <node label>, 'properties': { 'name': <name>, 'account': <account#> } }
    # with the exception of relationships as they are not required to be named, properties can be empty {}
    # the name must be unique for each label type
    #====================================
    def _make_node(self,tx,args):
        tx.run(
            query = "MERGE (n:" f"{args['label']}" " {name:$properties.name,account:$properties.account}) ON CREATE set n=$properties",
            parameters={'properties':args['properties']}
        )

    def _make_rel(self,tx,n1,rel,n2):
        tx.run(
            query = "MATCH (n1:" f"{n1['label']}" "{name:$n1.name,account:$n1.account}) "
                    "MATCH (n2:" f"{n2['label']}" "{name:$n2.name,account:$n2.account}) "
                    "MERGE (n1)-[r:" f"{rel['label']}" "]->(n2) ON CREATE set r=$properties",
            parameters={
                        'n1':n1['properties'],
                        'properties':rel['properties'],
                        'n2':n2['properties']
                        }
        )

    def write_nodes(self,nodelist):
        with self._session.begin_transaction() as tx:
            try:
                for n in nodelist:
                    self._make_node(tx,n)
            except Exception as e:
                tx.rollback()
            else:
                tx.commit()

    def write_relations(self,tuples):
        with self._session.begin_transaction() as tx:
            try:
                for t in tuples:
                    self._make_rel(tx,t[0],t[1],t[2])
            except Exception as e:
                tx.rollback()
            else:
                tx.commit()

    def clear_database(self):
        self._session.run(
            query = "MATCH(n) DETACH DELETE n"
        )
