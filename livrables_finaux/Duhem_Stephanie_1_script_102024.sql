-- LES REQUÊTES SQL DEMANDÉES

-- Question : En excluant les commandes annulées, quelles sont les commandes récentes de moins de 3 mois que les clients ont reçues avec au moins 3 jours de retard ?

WITH latest_order as (select max(order_purchase_timestamp) from orders) -- trier les commandes en commençant par les plus récentes
SELECT *, JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_estimated_delivery_date) as ecart -- calcul de l'écart entre la date de livraison estimée et la date effective de livraison
FROM orders WHERE order_purchase_timestamp >= DATE((SELECT * from latest_order), '-3 months') AND ecart >= 3 -- Sélection des commandes de moins de 3 mois et reçues avec au moins 3 jours de retard sur la date delivraison prévue

AND order_status <> 'canceled' -- Exclusion des commandes annulées


-- Question : Qui sont les vendeurs ayant généré un chiffre d'affaires de plus de 100 000 Real sur des commandes livrés via Olist ?

with orders_joined as (select distinct  
    order_items.seller_id,
    order_items.order_id,
    order_items.price,
    orders.order_purchase_timestamp 
    from order_items 
        inner join orders on orders.order_id = order_items.order_id
    where orders.order_status = 'delivered'
        order by seller_id, order_purchase_timestamp), -- Sélection des données vendeurs uniques et des données concernant leurs commandes déjà livrées, triées par dates et id
aggregation as (select seller_id, sum(price) as ca_total 
    from orders_joined group by seller_id) -- Calcul de la somme des ventes effectuées pour chaque vendeur
select * from aggregation where ca_total > 100000 -- Sélectionner les vendeurs dont la somme des ventes est supérieur strictement à 100000 real
order by ca_total desc -- Trier les résultats par ordre décroissant

-- Question : Qui sont les nouveaux vendeurs (moins de 3 mois d'ancienneté) qui sont déjà très engagés avec la plateforme (ont déjà vendu plus de 30 produits) ?

with latest_order as(select max(order_purchase_timestamp) from orders),
orders_joined as (select distinct 
    order_items.seller_id, 
    order_items.order_id, 
    orders.order_purchase_timestamp
from order_items 
    inner join orders on orders.order_id = order_items.order_id
    where orders.order_status = 'delivered'
    order by seller_id, order_purchase_timestamp), -- Sélection des données vendeurs uniques et des données concernant leurs commandes déjà livrées, triées par dates et id
aggregation as (select seller_id, count(order_id) as nb_produits_vendus -- Décompte du nombre de produits vendus par vendeur en comptant le nbre de numéro de commande 
    from orders_joined group by seller_id having min(order_purchase_timestamp) > DATE((SELECT * from latest_order), '-3 months')) -- Sélection des vendeurs qui ont moins de 3 mois d'ancienneté
select * from aggregation
where nb_produits_vendus > 30 -- Sélection des vendeurs qui ont vendu au moins 30 produits

-- Question : Quels sont les 5 codes postaux, enregistrant plus de 30 commandes, avec le pire review score moyen sur les 12 derniers mois ?

WITH latest_order as(select max(order_purchase_timestamp) from orders),
join_orders_geoloc as (SELECT distinct o.order_id, o.order_purchase_timestamp, c.customer_zip_code_prefix -- Sélection des données des commandes avec le code postal de livraison de la commande, la date et l'id
FROM orders as o
    INNER JOIN customers as c
    ON o.customer_id = c.customer_id), -- Jointure avec l'id client lors de la commande pour récupérer après la note client sur la commande
average_review_score_per_zip as (
    SELECT customer_zip_code_prefix, AVG(review_score) as avg_review_score, COUNT(review_score) as nb_reviews -- Calcul de la moyenne des notes des clients en fonction du code postal de livraison de la commande
    FROM order_reviews as r
    INNER JOIN join_orders_geoloc as o
    on r.order_id = o.order_id
    WHERE order_purchase_timestamp >= DATE((SELECT * from
latest_order), '-12 months') -- Sélection des commandes sur les 12 derniers mois
    GROUP BY customer_zip_code_prefix -- Résultat groupé par code postal
)
SELECT * From average_review_score_per_zip
where nb_reviews > 30 -- Sélection des résultats pour les codes postaux enregistrant au moins 30 commandes sur la période choisie précédemment
order by avg_review_score -- Trier les résultats par ordre croissant
LIMIT 5 -- Limitations des résultats aux 5 premiers de la liste, donc les 5 au score moyen le plus bas 